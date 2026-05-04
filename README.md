# Neuro Flask Backend

This is the backend for a platform catered towards students with autism, connecting Students, Parents, and Teachers. The application is built using Flask and uses MongoDB for data storage. It features role-based functionality and includes a machine learning prediction pipeline (dysgraphia/environmental factors) based on skeletal/landmark feature extraction.

## Features

- **Role-Based System**: Distinct profiles and functionalities for Students, Parents, and Teachers.
- **Custom Authentication**: Simplified ID-based authentication without JWT. Uses MongoDB `_id` from a centralized `users` collection sent via the `X-User-Id` header.
- **Parent-Student Linking**: Parents can link their accounts to students using one-time pairing codes.
- **History Tracking**: Track student history and reports.
- **Machine Learning Integration**: 
  - An endpoint (`/predict`) that accepts CSV data of landmark points.
  - Extracts spatial and temporal features (angles, velocities, 3D distances).
  - Uses a pre-trained Random Forest model (`multi_rf_model.pkl`) to predict triggers or normal behavior, as well as environmental factors.

## Prerequisites

- Python 3.12+
- MongoDB instance (Local or Atlas)
- `uv` or `pip` for dependency management

## Setup & Installation

1. **Clone the repository and navigate to the folder:**
   ```bash
   cd "Neuro flask"
   ```

2. **Install dependencies:**
   Using `pip` with the requirements file:
   ```bash
   pip install -r requirements.txt
   ```
   *Note: This project also contains a `pyproject.toml` and can be used with `uv`.*

3. **Environment Variables:**
   Create a `.env` file in the root directory (if not already present) and configure your MongoDB connection:
   ```env
   MONGO_URL=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<dbname>
   ```
   *(Ensure you replace the credentials with your actual MongoDB connection string).*

4. **Machine Learning Models:**
   Place the required pre-trained model files in a `models/` directory at the project root:
   - `models/multi_rf_model.pkl`
   - `models/env_label_encoder.pkl`

5. **Run the Server:**
   ```bash
   flask --app app.main run --debug
   # OR
   python app/main.py
   ```
   The server runs on `http://localhost:5000` by default.

## API Endpoints Overview

### Authentication
- `POST /auth/signin`: Sign in for all users. Returns the user `_id` and `role`.
- `POST /auth/student/signup`: Register a new student.
- `POST /auth/parent/signup`: Register a new parent.
- `POST /auth/teacher/signup`: Register a new teacher.
- `POST /auth/signout`: Sign out endpoint.

### Profiles & Users (Requires `X-User-Id` header)
- `GET /profile`: Get the logged-in user's profile and role-specific data.
- `GET /user/students`: (Parent) Retrieve the list of linked students and their history.
- `POST /user/add-student`: (Parent) Link a student using a pairing code.

### Student Actions (Requires `X-User-Id` header)
- `GET /student/pairing-code`: Generate a one-time pairing code for a parent to link.
- `POST /student/add-history`: Add a report/record to the student's history array.

### Prediction
- `POST /predict`: Upload a CSV file containing sequential landmark data to get predictions based on the ML model.

## Technologies Used
- **Flask**: Web Framework
- **PyMongo**: MongoDB driver
- **Pandas & NumPy**: Data manipulation and feature extraction
- **Scikit-learn / Joblib**: Machine Learning model loading and prediction
- **Pydantic**: Data validation
