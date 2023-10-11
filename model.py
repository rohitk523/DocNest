from pydantic import BaseModel

class Docs(BaseModel):
	User: str
	Aadhar: str
	Pan: str
	Phone: int

allDocuments = []
