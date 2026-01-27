def parse_yaml_config(config_string):
    """Parse YAML configuration string into dictionary."""
    import yaml
    return yaml.safe_load(config_string)

def format_json_output(data):
    """Format dictionary as JSON string."""
    import json
    return json.dumps(data, indent=2)

def load_env_file(file_path):
    """Load environment variables from .env file."""
    env_vars = {}
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                key, value = line.split('=', 1)
                env_vars[key.strip()] = value.strip()
    return env_vars
