import os
import subprocess
from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_bcrypt import Bcrypt
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user
import mysql.connector

# ---------------- Existing Setup ----------------
app = Flask(__name__)
CORS(app)
bcrypt = Bcrypt(app)

app.config['SECRET_KEY'] = 'supersecretkey'

BASE_DIR = os.path.expanduser("~/Desktop/VistaProject")
PIPELINE_SCRIPT = os.path.join(BASE_DIR, "sentinel", "run_full_pipeline.sh")

# ---------------- MySQL Setup ----------------
db = mysql.connector.connect(
    host="localhost",
    user="root",             # change if needed
    password="yourpassword", # change if needed
    database="vistaproject"
)
cursor = db.cursor(dictionary=True)

# ---------------- Flask-Login Setup ----------------
login_manager = LoginManager(app)

class User(UserMixin):
    def __init__(self, id, email, password):
        self.id = id
        self.email = email
        self.password = password

@login_manager.user_loader
def load_user(user_id):
    cursor.execute("SELECT * FROM users WHERE id=%s", (user_id,))
    user = cursor.fetchone()
    if user:
        return User(user['id'], user['email'], user['password'])
    return None

# ---------------- 🔑 Auth Routes (NEW) ----------------
@app.route("/register", methods=["POST"])
def register():
    data = request.json
    email = data.get("email")
    password = bcrypt.generate_password_hash(data.get("password")).decode("utf-8")

    cursor.execute("INSERT INTO users (email, password) VALUES (%s, %s)", (email, password))
    db.commit()
    return jsonify({"message": "User registered successfully!"})

@app.route("/login", methods=["POST"])
def login():
    data = request.json
    email = data.get("email")
    password = data.get("password")

    cursor.execute("SELECT * FROM users WHERE email=%s", (email,))
    user = cursor.fetchone()
    if not user or not bcrypt.check_password_hash(user["password"], password):
        return jsonify({"error": "Invalid credentials"}), 401

    user_obj = User(user["id"], user["email"], user["password"])
    login_user(user_obj)
    return jsonify({"message": "Login successful!"})

@app.route("/logout", methods=["POST"])
@login_required
def logout():
    logout_user()
    return jsonify({"message": "Logged out"})

# ---------------- ✅ Your Existing Routes ----------------
@app.route("/run_pipeline", methods=["POST"])
def run_pipeline():
    try:
        data = request.json
        region = data.get("region")
        minLon = data.get("minLon")
        minLat = data.get("minLat")
        maxLon = data.get("maxLon")
        maxLat = data.get("maxLat")

        if not all([region, minLon, minLat, maxLon, maxLat]):
            return jsonify({"error": "Missing parameters"}), 400

        cmd = [
            PIPELINE_SCRIPT,
            region, str(minLon), str(minLat), str(maxLon), str(maxLat)
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)

        return jsonify({
            "status": "ok",
            "stdout": result.stdout,
            "stderr": result.stderr,
            "processed_data": os.path.join(BASE_DIR, "processed_data", region),
            "reports": os.path.join(BASE_DIR, "reports", f"{region}_report.xlsx")
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "Flask backend is running"})


# ---------------- Main ----------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)  # ✅ kept 5001 as you had
