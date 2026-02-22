import requests

BASE_URL = "http://localhost:3000"

def test_signup(endpoint, data, role_name):
    print(f"\n--- Testing {role_name} Sign Up ---")
    try:
        response = requests.post(f"{BASE_URL}{endpoint}", json=data)
        print(f"Status: {response.status_code}")
        try:
            print(f"Response: {response.json()}")
        except:
            print(f"Response (text): {response.text}")
    except Exception as e:
        print(f"Connection Error: {e}")

if __name__ == "__main__":
    print(f"Targeting Server: {BASE_URL}")

    # 1. Student
    student_data = {
        "fullName": "John Student",
        "email": "student@example.com",
        "description": "A dedicated student",
        "password": "password123",
        "dob": "2005-06-15",
        "institution": "Springfield High"
    }
    test_signup("/auth/student/signup", student_data, "Student")

    # 2. Parent
    parent_data = {
        "fullName": "Jane Parent",
        "email": "parent@example.com",
        "password": "password123"
    }
    test_signup("/auth/parent/signup", parent_data, "Parent")

    # 3. Teacher
    teacher_data = {
        "fullName": "Mr. Teacher",
        "email": "teacher@example.com",
        "password": "password123",
        "institution": "Springfield High"
    }
    test_signup("/auth/teacher/signup", teacher_data, "Teacher")

    # --- Sign In Tests ---
    print("\n" + "="*30)
    print("      TESTING SIGN IN")
    print("="*30)

    # 4. Student Sign In
    student_login = {
        "email": "student@example.com",
        "password": "password123"
    }
    test_signup("/auth/student/signin", student_login, "Student Login")

    # 5. Parent Sign In
    parent_login = {
        "email": "parent@example.com",
        "password": "password123"
    }
    test_signup("/auth/parent/signin", parent_login, "Parent Login")

    # 6. Teacher Sign In
    teacher_login = {
        "email": "teacher@example.com",
        "password": "password123"
    }
    test_signup("/auth/teacher/signin", teacher_login, "Teacher Login")
