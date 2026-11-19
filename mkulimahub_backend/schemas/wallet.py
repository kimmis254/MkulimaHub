from pydantic import BaseModel


class WithdrawPayload(BaseModel):
    amount: float
