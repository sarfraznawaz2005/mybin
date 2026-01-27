import logging
from datetime import datetime

class CustomLogger:
    def __init__(self, name):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.INFO)
        
        handler = logging.FileHandler(f"{name}.log")
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        self.logger.addHandler(handler)
    
    def info(self, message):
        self.logger.info(message)
    
    def error(self, message):
        self.logger.error(message)
    
    def warn(self, message):
        self.logger.warning(message)

# Usage example
if __name__ == "__main__":
    logger = CustomLogger("app")
    logger.info("Application started")
    logger.warn("This is a warning")
    logger.error("An error occurred")
