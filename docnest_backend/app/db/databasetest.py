import psycopg2

# Supabase connection string
conn_string = "postgresql://postgres.pofobwqjhpeplqfcbfqz:ETHN$hnt789@aws-0-ap-south-1.pooler.supabase.com:6543/postgres"

try:
    # Try to connect to the Supabase database using the connection string
    conn = psycopg2.connect(conn_string)
    print("Connection successful!")

    # You can now execute queries or perform other database operations
    with conn.cursor() as cur:
        cur.execute("SELECT 1;")
        result = cur.fetchone()
        print(f"Result: {result}")

    conn.close()

except psycopg2.Error as e:
    print(f"Error connecting to the database: {e}")