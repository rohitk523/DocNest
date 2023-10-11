from fastapi import FastAPI, HTTPException
from model import Docs

app = FastAPI()

DocumentData = {"Rohit": {"Aadhar": 123, "Pan": 456, "Phone":7743,},
                "Renuka": {"Aadhar": 12, "Pan": 45, "Phone":774,},
                "Sunita": {"Aadhar": 1,"Pan": 4, "Phone":77,}}

@app.post('/')
async def doc(doc: Docs):
    return doc
        
