from fastapi import FastAPI

app = FastAPI()

@app.get('/')
async def doc():
    return {"message": "this is docs"}