from flask import Flask, jsonify, request
from functools import wraps

app = Flask(__name__)

def handle_errors(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        try:
            return f(*args, **kwargs)
        except Exception as e:
            return jsonify({'error': str(e)}), 500
    return decorated

@app.route('/api/users', methods=['GET'])
@handle_errors
def get_users():
    users = [{'id': 1, 'name': 'Alice'}, {'id': 2, 'name': 'Bob'}]
    return jsonify(users)

@app.route('/api/users/<int:user_id>', methods=['GET'])
@handle_errors
def get_user(user_id):
    return jsonify({'id': user_id, 'name': 'Alice'})
