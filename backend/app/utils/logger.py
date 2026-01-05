from loguru import logger
import sys

def setup_logging():
    logger.remove()
    logger.add(sys.stderr, level="INFO", backtrace=False, diagnose=False)
    return logger
