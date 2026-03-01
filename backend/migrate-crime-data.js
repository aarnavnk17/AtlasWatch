require('dotenv').config({ path: __dirname + '/.env' });
const mongoose = require('mongoose');
const fs = require('fs');

const MONGO_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/atlaswatch';

const crimeStatSchema = new mongoose.Schema({
    state: { type: String, required: true },
    city: { type: String, required: true },
    risk: String,
    score: Number,
    areas: mongoose.Schema.Types.Mixed,
    lastUpdated: { type: Date, default: Date.now }
});

const CrimeStat = mongoose.model('CrimeStat', crimeStatSchema);

async function migrate() {
    try {
        console.log('Connecting to MongoDB...');
        await mongoose.connect(MONGO_URI);

        const data = JSON.parse(fs.readFileSync(__dirname + '/data/crime_data.json', 'utf8'));
        let count = 0;

        // Clear existing data to avoid duplicates if re-running
        await CrimeStat.deleteMany({});
        console.log('Cleared existing CrimeStat collection.');

        for (const [stateName, cities] of Object.entries(data)) {
            for (const [cityName, stats] of Object.entries(cities)) {
                await CrimeStat.create({
                    state: stateName,
                    city: cityName,
                    risk: stats.risk,
                    score: stats.score,
                    areas: stats.areas
                });
                count++;
            }
        }

        console.log(`Successfully migrated ${count} cities to MongoDB.`);
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        await mongoose.disconnect();
        process.exit(0);
    }
}

migrate();
