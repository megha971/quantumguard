// backend/src/services/ipfs.js
const { create } = require("ipfs-http-client");
const { Buffer } = require("buffer");

let client;

const getClient = () => {
  if (!client) {
    // Infura IPFS or local node
    if (process.env.IPFS_PROJECT_ID && process.env.IPFS_PROJECT_SECRET) {
      const auth = "Basic " + Buffer.from(`${process.env.IPFS_PROJECT_ID}:${process.env.IPFS_PROJECT_SECRET}`).toString("base64");
      client = create({
        host: "ipfs.infura.io",
        port: 5001,
        protocol: "https",
        headers: { authorization: auth },
      });
    } else {
      client = create({ host: "127.0.0.1", port: 5001, protocol: "http" });
    }
  }
  return client;
};

const uploadJSON = async (data) => {
  const ipfs = getClient();
  const content = JSON.stringify(data);
  const result = await ipfs.add(content, { pin: true });
  return result.cid.toString();
};

const uploadBuffer = async (buffer, mimeType) => {
  const ipfs = getClient();
  const result = await ipfs.add(buffer, { pin: true });
  return result.cid.toString();
};

const fetchJSON = async (hash) => {
  const ipfs = getClient();
  const chunks = [];
  for await (const chunk of ipfs.cat(hash)) {
    chunks.push(chunk);
  }
  return JSON.parse(Buffer.concat(chunks).toString());
};

module.exports = { uploadJSON, uploadBuffer, fetchJSON };
