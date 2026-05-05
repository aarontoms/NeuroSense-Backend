import os
import glob
import pandas as pd
import numpy as np

fps = 30
window = 60
stride = 30

keep_ids = [0, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]


def rotate_point(x, y, cx, cy, angle):
    xr = (x - cx) * np.cos(-angle) - (y - cy) * np.sin(-angle)
    yr = (x - cx) * np.sin(-angle) + (y - cy) * np.cos(-angle)
    return xr, yr


def safe_mean(arr):
    return 0.0 if arr.size == 0 or np.all(np.isnan(arr)) else np.nanmean(arr)


def safe_std(arr):
    return 0.0 if arr.size == 0 or np.all(np.isnan(arr)) else np.nanstd(arr)


def extract_features(win):
    feats = {}
    points = {}

    if win["landmark_11_vis"].mean() < 0.5 or win["landmark_12_vis"].mean() < 0.5:
        return None

    lx, ly = win["landmark_11_x"], win["landmark_11_y"]
    rx, ry = win["landmark_12_x"], win["landmark_12_y"]

    msx, msy = (lx + rx) / 2, (ly + ry) / 2
    angle = np.arctan2(ry - ly, rx - lx)

    shoulder_width = np.sqrt((rx - lx) ** 2 + (ry - ly) ** 2)
    shoulder_width = np.where(shoulder_width == 0, np.nan, shoulder_width)

    for idx in keep_ids:
        try:
            x = win[f"landmark_{idx}_x"]
            y = win[f"landmark_{idx}_y"]
            z = win[f"landmark_{idx}_z"]
            vis = win[f"landmark_{idx}_vis"]

            mask = vis < 0.5
            x, y, z = x.mask(mask), y.mask(mask), z.mask(mask)

            xr, yr = rotate_point(x, y, msx, msy, angle)
            xr /= shoulder_width
            yr /= shoulder_width
            zr = z / shoulder_width

            points[idx] = (xr.values, yr.values, zr.values)
        except KeyError:
            points[idx] = (
                np.full(window, np.nan),
                np.full(window, np.nan),
                np.full(window, np.nan),
            )

    def dist3D(a, b):
        x1, y1, z1 = points[a]
        x2, y2, z2 = points[b]
        return np.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2 + (z1 - z2) ** 2)

    feats["dist_wrists_mean"] = safe_mean(dist3D(15, 16))
    feats["noseL_wrist_mean"] = safe_mean(dist3D(0, 15))
    feats["noseR_wrist_mean"] = safe_mean(dist3D(0, 16))

    def angle2D(a, b, c):
        ax, ay, _ = points[a]
        bx, by, _ = points[b]
        cx, cy, _ = points[c]

        v1 = np.stack([ax - bx, ay - by], axis=1)
        v2 = np.stack([cx - bx, cy - by], axis=1)

        norm = np.linalg.norm(v1, axis=1) * np.linalg.norm(v2, axis=1)
        norm[norm == 0] = np.nan

        dot = np.sum(v1 * v2, axis=1)
        return np.arccos(np.clip(dot / norm, -1, 1))

    feats["elbowL_mean"] = safe_mean(angle2D(11, 13, 15))
    feats["elbowR_mean"] = safe_mean(angle2D(12, 14, 16))

    for side, (w, p, i, t) in zip(["L", "R"], [(15, 17, 19, 21), (16, 18, 20, 22)]):
        feats[f"{side}_wrist_pinky_mean"] = safe_mean(dist3D(w, p))
        feats[f"{side}_wrist_index_mean"] = safe_mean(dist3D(w, i))
        feats[f"{side}_wrist_thumb_mean"] = safe_mean(dist3D(w, t))

    for idx in [15, 16, 17, 18, 19, 20, 21, 22]:
        x, y, z = points[idx]
        vel = np.sqrt(np.diff(x) ** 2 + np.diff(y) ** 2 + np.diff(z) ** 2)
        feats[f"landmark_{idx}_vel_mean"] = safe_mean(vel)
        feats[f"landmark_{idx}_vel_std"] = safe_std(vel)

    return feats



