alias RyugraphEx.{Database, Connection, Graph}

{:ok, db} = Database.in_memory()
{:ok, conn} = Connection.new(db)

# Create test data
Connection.query!(conn, """
  CREATE NODE TABLE TestNode(id INT64, PRIMARY KEY(id));
""")

Connection.query!(conn, """
  CREATE REL TABLE TestRel(FROM TestNode TO TestNode);
""")

# Create some nodes
Connection.query!(conn, "CREATE (n:TestNode {id: 1});")
Connection.query!(conn, "CREATE (n:TestNode {id: 2});")
Connection.query!(conn, "CREATE (n:TestNode {id: 3});")

# Create relationships
Connection.query!(conn, """
  MATCH (a:TestNode), (b:TestNode)
  WHERE a.id = 1 AND b.id = 2
  CREATE (a)-[:TestRel]->(b);
""")

Connection.query!(conn, """
  MATCH (a:TestNode), (b:TestNode)
  WHERE a.id = 2 AND b.id = 3
  CREATE (a)-[:TestRel]->(b);
""")

# Test different shortest path syntaxes
IO.puts("Testing shortest path syntaxes...")

# Try 1: shortestPath function
result1 = Connection.query(conn, """
  MATCH p = shortestPath((a:TestNode)-[*]->(b:TestNode))
  WHERE a.id = 1 AND b.id = 3
  RETURN p;
""")
IO.puts("1. shortestPath: #{inspect(result1)}")

# Try 2: SHORTEST keyword
result2 = Connection.query(conn, """
  MATCH SHORTEST p = (a:TestNode)-[*]->(b:TestNode)
  WHERE a.id = 1 AND b.id = 3
  RETURN p;
""")
IO.puts("2. SHORTEST: #{inspect(result2)}")

# Try 3: ALL SHORTEST PATHS
result3 = Connection.query(conn, """
  MATCH ALL SHORTEST PATHS p = (a:TestNode)-[*]->(b:TestNode)
  WHERE a.id = 1 AND b.id = 3
  RETURN p;
""")
IO.puts("3. ALL SHORTEST PATHS: #{inspect(result3)}")

# Try 4: Just regular path with LIMIT 1
result4 = Connection.query(conn, """
  MATCH p = (a:TestNode)-[*]->(b:TestNode)
  WHERE a.id = 1 AND b.id = 3
  RETURN p LIMIT 1;
""")
IO.puts("4. Regular path with LIMIT 1: #{inspect(result4)}")

# Try 5: Regular path with variable-length relationships
result5 = Connection.query(conn, """
  MATCH p = (a:TestNode)-[*1..10]->(b:TestNode)
  WHERE a.id = 1 AND b.id = 3
  RETURN p;
""")
IO.puts("5. Variable-length path: #{inspect(result5)}")