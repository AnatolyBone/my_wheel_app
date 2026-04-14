import OpenAI from "openai";

console.log("start...");

const client = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

const res = await client.responses.create({
  model: "gpt-5-nano",
  input: "1 short sentence about AI",
});

console.log("RESULT:");
console.log(res.output_text);