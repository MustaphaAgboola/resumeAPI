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