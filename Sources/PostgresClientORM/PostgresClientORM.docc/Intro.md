# Intro

Welcome to **PostgresClientORM**, the **ORM** for data in **PostgreSQL**

## Overview

**PostgresClientORM** is an **ORM** for storing objects in Postgres. It uses the package *PostgresNIO* for the connection to Postgres. **PostgresClientORM** has the advantage over **Fluent** that it's more Swift friendly, faster, and has a lower memory footprint for loaded objects. The advantage of Fluent us that it's database agnostic.

### Connection

The connection to **Postgres** database is controlled via environment variables. If the environment **DATABASE_URL** exists, it is used to control the connection, otherwise the set of following enviroment variables is used:


**DATABASE_HOST**

**DATABASE_PORT** (defaults to 5432 if not present)

**DATABASE_USER**

**DATABASE_PASSWORD**

**DATABASE_SSL** (defaults to true if not present)



