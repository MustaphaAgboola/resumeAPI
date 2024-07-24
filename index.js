const AWS = require('aws-sdk');
const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
    const params = {
        TableName: "ResumeTable"
    };
    try {
        const data = await dynamodb.scan(params).promise();
        return {
            statusCode: 200,
            body: JSON.stringify(data.Items),
            headers: {
                'Content-Type': 'application/json'
            }
        };
    } catch (error){
        console.error(error);
        return {
            statusCode: 500,
            body: JSON.stringify({ 'error': 'could not retrieve items' }),
            headers: {
                'Content-Type': 'application/json'
            }
        };

    }
};


// https://chatgpt.com/c/46acca9a-d6f0-4da5-98f1-6a25403f95bb