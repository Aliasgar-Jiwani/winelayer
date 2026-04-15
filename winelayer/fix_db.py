import sqlite3
import os

db_path = os.path.join(os.path.expanduser("~"), "AppData", "Local", "winelayer", "winelayer.db")
conn = sqlite3.connect(db_path)
conn.execute("UPDATE apps SET status='installed' WHERE status='running'")
conn.commit()
print(f"Fixed {conn.total_changes} stuck app(s)")
conn.close()
