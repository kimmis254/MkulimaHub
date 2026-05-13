import os
import base64
import json
import requests
from datetime import datetime
from requests.auth import HTTPBasicAuth
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from dotenv import load_dotenv

load_dotenv()

class MpesaClient:
    def __init__(self):
        self.env = os.getenv("MPESA_ENVIRONMENT", "sandbox")
        if self.env == "production":
            self.base_url = "https://api.safaricom.co.ke"
        else:
            self.base_url = "https://sandbox.safaricom.co.ke"
            
        self.consumer_key = os.getenv("MPESA_CONSUMER_KEY")
        self.consumer_secret = os.getenv("MPESA_CONSUMER_SECRET")
        self.shortcode = os.getenv("MPESA_BUSINESS_SHORTCODE", "174379")
        self.passkey = os.getenv("MPESA_PASSKEY", "bfb279f9aa9bdbcf158e97dd71a467cd2e0c893059b10f78e6b72ada1ed2c919")
        self.callback_base_url = os.getenv("BACKEND_BASE_URL")

        # 🔥 THE FIX: Create a resilient HTTP Session with a built-in Retry Engine!
        self.session = requests.Session()
        # If Daraja drops the connection, it will silently retry 3 times, waiting 0.5s between tries.
        retries = Retry(total=3, backoff_factor=0.5, status_forcelist=[ 500, 502, 503, 504 ])
        self.session.mount('https://', HTTPAdapter(max_retries=retries))

    def get_access_token(self):
        """Authenticates with Safaricom and returns a temporary access token."""
        api_url = f"{self.base_url}/oauth/v1/generate?grant_type=client_credentials"
        
        try:
            # 🔥 Use the resilient session instead of plain requests
            response = self.session.get(
                api_url, 
                auth=HTTPBasicAuth(self.consumer_key, self.consumer_secret),
                timeout=10
            )
            response.raise_for_status()
            return response.json().get("access_token")
        except requests.exceptions.RequestException as e:
            print(f"🚨 Failed to get M-Pesa Access Token. Daraja might be down: {e}")
            return None

    def generate_password(self, timestamp):
        """Generates the Base64 encoded password required for STK Push."""
        data_to_encode = self.shortcode + self.passkey + timestamp
        encoded_string = base64.b64encode(data_to_encode.encode("utf-8")).decode("utf-8")
        return encoded_string

    def format_phone_number(self, phone):
        """Converts 07XX... or +2547XX... to the required 2547XX... format."""
        phone = str(phone).strip().replace("+", "")
        if phone.startswith("0"):
            phone = "254" + phone[1:]
        elif phone.startswith("7") or phone.startswith("1"):
            phone = "254" + phone
        return phone

    def trigger_stk_push(self, phone_number: str, amount: float, order_id: str):
        """Sends the PIN prompt to the user's phone."""
        token = self.get_access_token()
        if not token:
            return {"error": "Authentication failed. Could not reach Safaricom."}

        api_url = f"{self.base_url}/mpesa/stkpush/v1/processrequest"
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }

        # Daraja strictly requires the timestamp in this exact format
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        password = self.generate_password(timestamp)
        formatted_phone = self.format_phone_number(phone_number)
        print(f"🔍 DEBUG - Sending Webhook URL to Daraja: {self.callback_base_url}/api/payments/webhook/stk")
        payload = {
            "BusinessShortCode": self.shortcode,
            "Password": password,
            "Timestamp": timestamp,
            "TransactionType": "CustomerPayBillOnline",
            "Amount": int(amount), # Daraja requires integers, no decimals
            "PartyA": formatted_phone, # The person paying
            "PartyB": self.shortcode,  # The business receiving the funds
            "PhoneNumber": formatted_phone,
            # 🔥 This is where Safaricom will send the receipt once the user types their PIN!
            "CallBackURL": f"{self.callback_base_url}/api/payments/webhook/stk",
            "AccountReference": f"ORD-{order_id}",
            "TransactionDesc": f"Payment for Order {order_id}"
        }

        try:
            # 🔥 Use the resilient session here too
            response = self.session.post(api_url, json=payload, headers=headers, timeout=15)
            # Log the exact response from Safaricom to help with debugging
            print(f"📡 Daraja Response: {response.status_code} - {response.text}")
            
            data = response.json()
            if response.status_code == 200 and "CheckoutRequestID" in data:
                return {
                    "success": True, 
                    "checkout_id": data["CheckoutRequestID"],
                    "merchant_id": data.get("MerchantRequestID"),
                    "message": "STK Push sent successfully"
                }
            return {"error": data.get("errorMessage", "Failed to initiate push")}
            
        except Exception as e:
            print(f"🚨 STK Push Error: {e}")
            return {"error": str(e)}