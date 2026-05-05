import axios from 'axios';

const API = axios.create({
  baseURL: import.meta.env.VITE_API_BASE || 'https://mv1z79jg-5000.inc1.devtunnels.ms/',
  timeout: 8000,
});

export default API;

export const registerStudent = (payload) =>
  API.post('/register_student', payload).then(r => r.data);

export const loginStudent = (payload) =>
  API.post('/login_student', payload).then(r => r.data);

export const loginAdmin = (payload) =>
  API.post('/login_admin', payload).then(r => r.data);

export const startStimulus = (payload) =>
  API.post('/start_stimulus', payload).then(r => r.data);

export const nextInstruction = (studentId) =>
  API.get(`/next_instruction/${studentId}`).then(r => r.data);

export const sendFrame = (payload) =>
  API.post('/frame', payload).then(r => r.data);

export const endStimulus = (payload) =>
  API.post('/end_stimulus', payload).then(r => r.data);

export const uploadVoice = (studentId, formData) =>
  API.post(`/upload_voice/${studentId}`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  }).then(r => r.data);

export const uploadStimulus = (formData) =>
  API.post('/upload_stimulus', formData, {
    headers: { 'Content-Type': 'multipart/form-data' }
  }).then(r => r.data);

export const analyticsSummary = () =>
  API.get('/analytics/summary').then(r => r.data);

export const analyticsByStudent = (studentId) =>
  API.get(`/analytics/student/${studentId}`).then(r => r.data);

export const analyticsStudentStimulus = (studentId) =>
  API.get(`/analytics/student/${studentId}/stimulus`).then(r => r.data);

export const analyticsStudentBest = (studentId) =>
  API.get(`/analytics/student/${studentId}/best`).then(r => r.data);

export const analyticsByStimulus = (stimulusId) =>
  API.get(`/analytics/stimulus/${stimulusId}`).then(r => r.data);

export const calibrateStart = (payload) =>
  API.post('/calibrate_start', payload).then(r => r.data);

export const calibrateSample = (payload) =>
  API.post('/calibrate_sample', payload).then(r => r.data);

export const calibrateFinish = (payload) =>
  API.post('/calibrate_finish', payload).then(r => r.data);
