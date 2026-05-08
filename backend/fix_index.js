const mongoose = require('mongoose');
require('dotenv').config({ path: __dirname + '/.env' });

const MONGO_URI = process.env.MONGODB_URI;

async function fixIndex() {
    try {
        await mongoose.connect(MONGO_URI);
        console.log("Connected to MongoDB...");
        
        const collection = mongoose.connection.collection('crimestats');
        
        console.log("Creating 2dsphere index on 'location' field...");
        await collection.createIndex({ location: "2dsphere" });
        
        console.log("✅ Index created successfully!");
        await mongoose.disconnect();
    } catch (err) {
        console.error("Failed to create index:", err.message);
    }
}

fixIndex();
