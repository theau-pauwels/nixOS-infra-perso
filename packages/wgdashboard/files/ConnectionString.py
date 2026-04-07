import configparser
import os

from flask import current_app
from sqlalchemy_utils import create_database, database_exists


def ConnectionString(database) -> str:
    configuration_path = os.getenv("CONFIGURATION_PATH", ".")
    configuration_file = os.path.join(configuration_path, "wg-dashboard.ini")

    parser = configparser.ConfigParser(strict=False)
    parser.read_file(open(configuration_file, "r+", encoding="utf-8"))

    sqlite_path = os.path.join(configuration_path, "db")
    if not os.path.isdir(sqlite_path):
      os.mkdir(sqlite_path)

    if parser.get("Database", "type") == "postgresql":
        cn = f'postgresql+psycopg://{parser.get("Database", "username")}:{parser.get("Database", "password")}@{parser.get("Database", "host")}/{database}'
    elif parser.get("Database", "type") == "mysql":
        cn = f'mysql+pymysql://{parser.get("Database", "username")}:{parser.get("Database", "password")}@{parser.get("Database", "host")}/{database}'
    else:
        cn = f'sqlite:///{os.path.join(sqlite_path, f"{database}.db")}'

    try:
        if not database_exists(cn):
            create_database(cn)
    except Exception as e:
        current_app.logger.error("Database error. Terminating...", e)
        exit(1)

    return cn
