from sqlalchemy import  Column, Integer, String

from database import Base


class Documentinfo(Base):
    __tablename__ = "documentinfo"
    
    id = Column(Integer, primary_key=True, index=True)
    userid = Column(String)
    aadhar = Column(String)
    pan = Column(String)
    phone = Column(Integer)


