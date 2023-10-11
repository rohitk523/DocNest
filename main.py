from fastapi import FastAPI, HTTPException
from model import Docs, allDocuments

app = FastAPI()

@app.post('/Post a Document')
async def addDoc(doc: Docs):
    allDocuments.append(doc)
    return doc


@app.get('/Get All Documents')
async def getAllDocs():
    return allDocuments
        
