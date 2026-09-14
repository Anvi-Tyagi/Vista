from flask import Flask
app = Flask(__name__)

@app.route("/ping")
def ping():
    return "pong 🏓"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)

from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

@app.route("/ping", methods=["GET"])
def ping():
    return jsonify({"status": "ok"}), 200

if __name__ == "__main__":
    # force port 5001
    app.run(host="0.0.0.0", port=5001, debug=True)
