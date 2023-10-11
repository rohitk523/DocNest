from pydantic import BaseModel

class Docs(BaseModel):
	user: str
	Aadhar: str
	Pan: str
	Phone: int

