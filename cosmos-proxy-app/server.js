const express = require("express");
const { CosmosClient } = require("@azure/cosmos");

const app = express();
const port = process.env.PORT || 8080;

const cosmosEndpoint = process.env.COSMOSDB_URI;
const cosmosKey = process.env.COSMOSDB_PRIMARY_KEY;
const cosmosDbName = "proxydb";
const cosmosContainerName = "items";

const client = new CosmosClient({
  endpoint: cosmosEndpoint,
  key: cosmosKey
});

app.use(express.json());

app.get("/", (req, res) => {
  res.send("✅ Cosmos DB Proxy is running.");
});

app.post("/items", async (req, res) => {
  try {
    const { database } = await client.databases.createIfNotExists({ id: cosmosDbName });
    const { container } = await database.containers.createIfNotExists({ id: cosmosContainerName });

    const { resource } = await container.items.create(req.body);
    res.status(201).send(resource);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message || String(err));
  }
});

app.get("/items", async (req, res) => {
  try {
    const { database } = await client.databases.createIfNotExists({ id: cosmosDbName });
    const { container } = await database.containers.createIfNotExists({ id: cosmosContainerName });

    const { resources } = await container.items.query("SELECT * FROM c").fetchAll();
    res.send(resources);
  } catch (err) {
    console.error(err);
    res.status(500).send(err.message || String(err));
  }
});

app.listen(port, () => {
  console.log(`🚀 Proxy listening on port ${port}`);
});
