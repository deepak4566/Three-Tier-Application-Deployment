const mongoose = require("mongoose");

module.exports = async () => {
    try {
        const connectionParams = {
            useNewUrlParser: true,
            useUnifiedTopology: true,
        };
        const useDBAuth = process.env.USE_DB_AUTH === "true" || !!(process.env.MONGO_USERNAME && process.env.MONGO_PASSWORD);
        if (useDBAuth) {
            connectionParams.user = process.env.MONGO_USERNAME;
            connectionParams.pass = process.env.MONGO_PASSWORD;
            connectionParams.authSource = process.env.MONGO_AUTH_SOURCE || "admin";
        }
        await mongoose.connect(
           process.env.MONGO_CONN_STR,
           connectionParams
        );
        console.log("Connected to database successfully.");
    } catch (error) {
        console.error("Could not connect to database:", error);
    }
};
