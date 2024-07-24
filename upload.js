const AWS = require('aws-sdk');
const fs = require('fs');
const path = require('path');

const dynamodb = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const dataPath = path.join(__dirname, 'data.json');
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));

  const params = {
    TableName: 'ResumeTable',
    Item: data
  };

  try {
    await dynamodb.put(params).promise();
    console.log("Data uploaded successfully");
  } catch (error) {
    console.error("Unable to upload data. Error JSON:", JSON.stringify(error, null, 2));
  }
};
