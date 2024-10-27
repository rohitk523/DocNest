from pydantic import BaseModel

class Docs(BaseModel):
	id: int
	user: str
	aadhar: str
	pan: str
	phone: int
        
	# class Config:
	# 	orm_mode = True