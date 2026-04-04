# Database Setup: Initializing PostgreSQL

The workshop application stores user data in PostgreSQL. This guide walks you through starting the database service, creating a dedicated user and database, and loading the initial schema with sample data.

## Step 1: Start the PostgreSQL Service

Ensure PostgreSQL is running on your system:

```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

The `enable` flag ensures PostgreSQL starts automatically on system reboot.

Verify it's running:

```bash
sudo systemctl status postgresql
```

You should see active (running) in the output. If there are any issues, check the logs:

```bash
sudo journalctl -u postgresql -n 50
```

## Step 2: Create the Database User

PostgreSQL comes with a default `postgres` superuser. We'll use this to create our workshop user with limited permissions.

Connect to PostgreSQL as the postgres user:

```bash
sudo -u postgres psql
```

You should see the PostgreSQL prompt: `postgres=#`

Now create the workshop user with password authentication:

```sql
CREATE USER workshopuser WITH PASSWORD 'workshoppass';
```

You should see the output: `CREATE ROLE`

Create the workshop database:

```sql
CREATE DATABASE workshopdb OWNER workshopuser;
```

Output: `CREATE DATABASE`

Grant all privileges on the database to our user:

```sql
GRANT ALL PRIVILEGES ON DATABASE workshopdb TO workshopuser;
```

Output: `GRANT`

Exit the PostgreSQL prompt:

```sql
\q
```

## Step 3: Create Tables and Seed Data

Now we'll load the initial database schema. The schema file is included in the workshop repository at `database/init.sql`.

First, navigate to the workshop directory where `database/init.sql` is located. Then run:

```bash
psql -U workshopuser -d workshopdb -h localhost -f database/init.sql
```

You should see output like:

```
CREATE TABLE
INSERT 0 3
```

This confirms that the users table was created and three sample users were inserted.

## Step 4: Verify the Setup

Let's confirm everything is working correctly. Connect to the database as the workshop user:

```bash
psql -U workshopuser -d workshopdb -h localhost
```

You're now connected to the workshop database. Run a simple query to verify the users table exists and contains data:

```sql
SELECT * FROM users;
```

You should see output like:

```
 id |      name      |        email        |         created_at
----+----------------+---------------------+----------------------------
  1 | Alice Johnson  | alice@example.com   | 2024-01-15 10:30:45.123456
  2 | Bob Smith      | bob@example.com     | 2024-01-15 10:30:45.234567
  3 | Carol White    | carol@example.com   | 2024-01-15 10:30:45.345678
(3 rows)
```

If you see these three records, the database is correctly set up.

You can also check the table structure:

```sql
\d users
```

This shows the table definition:

```
                           Table "public.users"
  Column   |            Type             | Collation | Nullable | Default
-----------+-----------------------------+-----------+----------+---------
 id        | integer                     |           | not null |
 name      | character varying(100)      |           | not null |
 email     | character varying(100)      |           | not null |
 created_at| timestamp without time zone |           |          | now()
```

Exit the PostgreSQL prompt:

```sql
\q
```

## Understanding the Workshop Database

The `users` table is intentionally simple, designed to demonstrate the full data flow:

- **Java Frontend** → reads and writes through the Python API
- **Python Backend** → executes SELECT, INSERT, DELETE queries against this table
- **PostgreSQL** → stores the data and records database operations as spans in EDOT

When you instrument both services with EDOT, you'll see:
- HTTP calls from Java to Python as distributed traces
- SQL queries from Python to PostgreSQL as child spans within those traces
- The complete execution flow with timing and error details

## Troubleshooting

**"psql: error: connection refused"**
- PostgreSQL service isn't running. Start it: `sudo systemctl start postgresql`
- Check it's listening on port 5432: `sudo netstat -tulnp | grep 5432`

**"role 'workshopuser' does not exist"**
- The user wasn't created. Repeat Step 2 carefully, ensuring you're in the `postgres=#` prompt.

**"database 'workshopdb' does not exist"**
- The database wasn't created. Run Step 2 and Step 3 again.

**"permission denied for database 'workshopdb'"**
- The user doesn't have permissions. Reconnect as postgres and run the GRANT statement from Step 2.

**"File 'database/init.sql' not found"**
- Verify you're in the correct directory where the workshop files are located.
- The path should be relative to where you're running the command from.

## Next Steps

Once the database is verified and populated with sample data, you're ready to start the application services. Proceed to **docs/02-run-the-app.md** to build and launch the Java frontend and Python backend.
