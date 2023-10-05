from fastapi import FastAPI, HTTPException

app = FastAPI()

DocumentData = {"Rohit": {"Aadhar": 123, "Pan": 456, "Phone":7743,},
                "Renuka": {"Aadhar": 12, "Pan": 45, "Phone":774,},
                "Sunita": {"Aadhar": 1, "Pan": 4, "Phone":77,}}

@app.get('/')
async def doc(name: str):
    for i in DocumentData.keys():
        if i == name:
            return DocumentData[name]
    else:
        raise(HTTPException(status_code=404, detail="USER NOT FOUND"))
        