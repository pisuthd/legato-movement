import assert from "assert"
import dotenv from "dotenv"

import PouchDB from 'pouchdb';
import axios from "axios"

import { env } from "../utils/envConfig.js"

import { VoyageEmbeddings } from "@langchain/community/embeddings/voyage";
import { MemoryVectorStore } from "langchain/vectorstores/memory";
import { ChatAnthropic } from "@langchain/anthropic";
import { BufferMemory } from "langchain/memory";
import { Document } from "langchain/document";
import {
    ChatPromptTemplate,
    PromptTemplate
} from "@langchain/core/prompts";
import { createStuffDocumentsChain } from "langchain/chains/combine_documents";
import { createRetrievalChain } from "langchain/chains/retrieval";

import {
    Markdown,
    italic,
    bold,
    link,
    quote,
    inlineCode,
    code,
} from '@scdev/declarative-markdown';

dotenv.config()

// A class that handles RAG processing

// Load API Keys
const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY || ""
assert(ANTHROPIC_API_KEY, "ANTHROPIC_API_KEY environment variable is missing from .env")

const VOYAGEAI_API_KEY = process.env.VOYAGEAI_API_KEY || ""
assert(VOYAGEAI_API_KEY, "VOYAGEAI_API_KEY environment variable is missing from .env")

const model = new ChatAnthropic({
    model: "claude-3-sonnet-20240229",
    temperature: 0
});

const defaultSystemPrompt = [
    `You are an AI agent assigned to review source code. `,
    `Use the following pieces of context to answer the question without referring to the example source code.`,
    `Use a maximum of two paragraph and maintain a formal tone to ensure it is suitable for inclusion in a security report.`,
    `\n\n`,
    `Context: {context}`,
].join("")

class RagChain {

    constructor() {
        this.is_init = false
        this.db = new PouchDB(`${env.NODE_ENV}:document`)
    }

    init = async (urls = []) => {
        if (this.is_init === false) { 
            let count = 0
            let fileIds = []
            for (let url of urls) {
                const { data } = await axios.get(url) 
                const key = `document-${count}`
                fileIds.push(key)
                await this.add(key, Buffer.from(data).toString('base64'))
                count = count + 1 
            }
            await this.build(fileIds)
            this.is_init = true
        }
    }

    // Build a RAG chain for querying the knowledge base
    build = async (fileIds, systemPrompt = defaultSystemPrompt) => {
        if (fileIds.length === 0) {
            throw new Error("None of the document IDs have been provided")
        }

        const docs = await this.load(fileIds)

        const vectorstore = await MemoryVectorStore.fromDocuments(
            docs,
            new VoyageEmbeddings()
        )

        const chatPrompt = ChatPromptTemplate.fromMessages([
            ["system", systemPrompt],
            ["human", "{input}"],
        ]);

        const questionAnswerChain = await createStuffDocumentsChain({ llm: model, prompt: chatPrompt });

        this.ragChain = await createRetrievalChain({
            retriever: vectorstore.asRetriever(),
            combineDocsChain: questionAnswerChain,
        });

    }

    query = async (input) => {
        if (!this.ragChain) {
            throw new Error("No RAG Chain setup.")
        }

        const result = await this.ragChain.invoke({
            input
        });

        return result.answer
    }

    generateReport = async (account, filename, source_code) => {

        const result = await this.query([
            "From the below source code, give code review including vulnerability score ranging from 0-100%",
            source_code,
        ].join())

        const mkd = new Markdown(`Review Summary - ${filename}`)
        mkd.paragraph(result)

        try {
            let entry = await this.db.get(account)
            entry.reports.push(mkd.render())
            await this.db.put(entry)
        } catch (e) {
            const item = {
                _id: account,
                reports: [
                    mkd.render()
                ]
            }
            await this.db.put(item)
        }

        return result
    }

    saveReport = async (account, title, report) => {
        const mkd = new Markdown(`${title}`)
        mkd.paragraph(report)

        try {
            let entry = await this.db.get(account)
            entry.reports.push(mkd.render())
            await this.db.put(entry)
        } catch (e) {
            const item = {
                _id: account,
                reports: [
                    mkd.render()
                ]
            }
            await this.db.put(item)
        }

    }

    getReport = async (account) => {
        try {
            const entry = await this.db.get(account) 
            return entry.reports
        } catch (e) {
            return []
        }
    }

    // DOCUMENT HANDLING

    // Store a new piece of knowledge in the knowledge base.
    // Key - This can be a filename like Pool.move or a classification such as MWC-102
    // Value - The data encoded in base64 format
    add = async (key, value) => {
        try {
            const entry = await this.db.get(key)
            entry.data = value
            await this.db.put(entry)
        } catch (e) {
            const item = {
                _id: key,
                data: value
            }
            await this.db.put(item)
        }
    }

    remove = async (key) => {
        const entry = await this.db.get(key)
        await this.db.remove(entry)
    }

    // Retrieve data of a single file from the database
    get = async (key) => {
        try {
            const entry = await this.db.get(key)
            return entry.data
        } catch (e) {
            return
        }
    }

    // Retrieve data from multiple files and wrap it into Langchain format
    load = async (keys = []) => {
        let result = []
        for (let key of keys) {
            const data = await this.get(key)
            if (data) {
                const pageContent = Buffer.from(data, 'base64').toString('utf8')
                const doc = new Document({ pageContent, metadata: { source: key } })
                result.push(doc)
            }
        }
        return result
    }


    destroy = async () => {
        await this.db.destroy();
    }
}

export default RagChain