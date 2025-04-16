from flask import Flask, request, jsonify
import os
import logging
from pathlib import Path
import json

app = Flask(__name__)

# Конфигурация
LOG_DIR = os.getenv('LOG_DIR', '/app/logs')
LOG_FILE = os.path.join(LOG_DIR, 'app.log')
Path(LOG_DIR).mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    filename=LOG_FILE,
    level=os.getenv('LOG_LEVEL', 'INFO'),
    format='%(asctime)s - %(message)s'
)

@app.route('/')
def home():
    return os.getenv('WELCOME_MSG', 'Welcome to the custom app')

@app.route('/status')
def status():
    return jsonify({"status": "ok"})

@app.route('/log', methods=['POST'])
def log():
    data = request.get_json()
    message = data.get('message', '')
    logging.info(message)
    return jsonify({"success": True})

@app.route('/logs')
def get_logs():
    try:
        with open(LOG_FILE, 'r') as f:
            return f.read()
    except FileNotFoundError:
        return jsonify({"error": "Logs not found"}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', '5000')))