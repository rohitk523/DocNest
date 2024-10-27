from fastapi import FastAPI,Depends
from model import Documentinfo
from schema import Docs
from database import engine, SessionLocal
import model
from sqlalchemy.orm import Session
from typing import Annotated


app = FastAPI()
model.Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post('/Add_document')
def create_user(db: Annotated[Session,Depends(get_db)],docsinfo: Docs ):
    db_doc = Documentinfo(userid = docsinfo.user, aadhar = docsinfo.aadhar, pan = docsinfo.pan, phone = docsinfo.phone)
    db.add(db_doc)
    db.commit()
    db.refresh(db_doc)
    return db_doc


@app.get('/Get_All_Documents')
def getAllDocuments(db: Annotated[Session, Depends(get_db)]):
    return db.query(Documentinfo).all()

