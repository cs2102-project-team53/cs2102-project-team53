# CS2102 Project Team 53

## SQL Project for CS2102 AY21/22 Semester 1

## Files
- `Project.pdf` - Project Instructions
- `ER.pdf` - Suggested ER Diagram
- `schema.sql` -  Database Schema
- `proc.sql` - Functions and Triggers
- `data.sql` - Dummy Data (Generated using the `generate.py` script) 
- `Final Report` - Final report summarising implementation/design details and roles/responsibilites



## Import Database
1. Log into PostgreSQL (e.g., with psql) and create a new database  
```sql
CREATE DATABASE my_db;
```

2. Create the database schema  
```sql
psql -d my_db -f schema.sql
```

3. Create functions and triggers  
```sql
psql -d my_db -f proc.sql
```

4. Insert data   
```sql
psql -d my_db -1 -f data.sql
```

## Generating Dummy Data
The `data.sql` file can be generated using the following steps:

1. Dummy data for each table can be added/updated under the respective file name in the `dummy_data` folder
2. Run `python generate_data.py`

## Team
- [Kevin Nathanael Mingtarja](https://www.linkedin.com/in/kevinmingtarja/)
- [Noel Mathew Isaac](https://www.linkedin.com/in/noelmathewisaac/)
- [Vanshiqa Agrawal](https://www.linkedin.com/in/vanshiqa-agrawal-71b228180/)
- [Wong Khia Xeng](https://www.linkedin.com/in/wong-khia-xeng-aba63a204/)
