from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class HelloRequest(BaseModel):
    name: str

@app.get("/api/omy")
def omy(name: str = "World"):
    return { "message": f"O my, hello, {name}!"}

@app.post("/api/helloUser") 
def hello(request: HelloRequest): 
    return {"message": f"Hello, {request.name}!"}