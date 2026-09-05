import os
import frappe
from frappe.utils import cint

def setup_database():
    pass

def bootstrap_database(verbose, source_sql=None):
    frappe.connect()
    import_db_from_sql(source_sql, verbose)
    frappe.connect()
    if "tabDefaultValue" not in frappe.db.get_tables():
        import sys
        from click import secho
        secho(
            "Table 'tabDefaultValue' missing in the restored site.",
            fg="red",
        )
        sys.exit(1)

def import_db_from_sql(source_sql=None, verbose=False):
    if verbose:
        print("Starting database import...")
    db_name = frappe.conf.db_name
    if not source_sql:
        source_sql = os.path.join(os.path.dirname(__file__), "framework_postgres.sql")
    db_user = os.environ.get("DB_USER") or frappe.conf.get("root_login") or db_name
    db_password = os.environ.get("DB_PASSWORD") or frappe.conf.get("root_password") or frappe.conf.db_password
    print(f"Restoring DB: name={db_name}, user={db_user}")
    from frappe.database.db_manager import DbManager
    DbManager(frappe.local.db).restore_database(
        verbose, db_name, source_sql, db_user, db_password
    )
    if verbose:
        print("Imported from database {}".format(source_sql))

def get_root_connection(root_login=None, root_password=None):
    if not frappe.local.flags.root_connection:
        user = os.environ.get("DB_USER") or root_login or frappe.conf.get("root_login")
        password = os.environ.get("DB_PASSWORD") or root_password or frappe.conf.get("root_password")
        frappe.local.flags.root_connection = frappe.database.get_db(
            socket=frappe.conf.db_socket,
            host=frappe.conf.db_host,
            port=frappe.conf.db_port,
            user=user,
            password=password,
            cur_db_name=frappe.conf.db_name,
        )
    return frappe.local.flags.root_connection

def drop_user_and_database(db_name, root_login, root_password):
    pass
