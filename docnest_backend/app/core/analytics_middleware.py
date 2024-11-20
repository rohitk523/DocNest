# # app/core/analytics_middleware.py
# from fastapi import Request
# from starlette.middleware.base import BaseHTTPMiddleware
# from ..services.analytics_service import AnalyticsService
# from ..db.session import SessionLocal
# import time

# class AnalyticsMiddleware(BaseHTTPMiddleware):
#     async def dispatch(self, request: Request, call_next):
#         # Start timer
#         start_time = time.time()
        
#         # Process request
#         response = await call_next(request)
        
#         # Calculate duration
#         duration = int((time.time() - start_time) * 1000)  # Convert to milliseconds
        
#         # Track API usage
#         try:
#             db = SessionLocal()
#             analytics_service = AnalyticsService(db)
            
#             properties = {
#                 "path": str(request.url.path),
#                 "method": request.method,
#                 "status_code": response.status_code
#             }
            
#             analytics_service.track_event(
#                 event_type="api_request",
#                 event_category="api",
#                 properties=properties,
#                 request=request,
#                 duration=duration
#             )
            
#         except Exception as e:
#             print(f"Error tracking analytics: {e}")
#         finally:
#             db.close()
        
#         return response