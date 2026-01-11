This checklist indicates the implementation status of MUST / SHOULD in the protocol specification.
Ref. https://github.com/open-telemetry/opentelemetry-proto/blob/main/docs/specification.md

# Protocol Details
## OTLP/gRPC
- [x] [MUST] All server components MUST support the following transport compression options:
  - [x] [MUST] No compression, denoted by none.
  - [x] [MUST] Gzip compression, denoted by gzip.

### OTLP/gRPC Concurrent Requests
- [ ] [SHOULD] The implementations that need to achieve high throughput SHOULD support concurrent Unary calls to achieve higher throughput.
- [ ] [SHOULD] The client SHOULD send new requests without waiting for the response to the earlier sent requests, essentially creating a pipeline of requests that are currently in flight that are not acknowledged.
- [ ] [SHOULD] The number of concurrent requests SHOULD be configurable.
- [ ] [SHOULD] The client implementation SHOULD expose an option to turn on and off the waiting during a shutdown.

### OTLP/gRPC Response
- Full Success
  - [x] [MUST] On success, the server response MUST be a Export<signal>ServiceResponse message.
  - [x] [MUST] The server MUST leave the partial_success field unset in case of a successful response.
  - [ ] [SHOULD] If the server receives an empty request the server SHOULD respond with success.
- Partial Success (NOTE: Currentry, it does not support partially accepting)
  - [ ] [MUST] The server response MUST be the same Export<signal>ServiceResponse message as in the Full Success case.
  - [ ] [MUST] The server MUST initialize the partial_success field, and it MUST set the respective rejected_spans, rejected_data_points, rejected_log_records or rejected_profiles field with the number of spans/data points/log records/profiles it rejected.
  - [ ] [MUST] Servers MAY also use the partial_success field to convey warnings/suggestions to clients even when the server fully accepts the request. The rejected_<signal> field MUST have a value of 0, and the error_message field MUST be non-empty.
  - [ ] [MUST] The client MUST NOT retry the request when it receives a partial success response where the partial_success is populated.
  - [ ] [SHOULD] The server SHOULD populate the error_message field with a human-readable error message in English.
- Failures
  - [ ] [MUST] Not-retryable errors indicate that telemetry data processing failed, and the client MUST NOT retry sending the same telemetry data. The client MUST drop the telemetry data.
  - [ ] [MUST] The server MUST indicate retryable errors using code Unavailable.
  - [ ] [SHOULD] Retryable errors indicate that telemetry data processing failed, and the client SHOULD record the error and may retry exporting the same data.
  - [ ] [SHOULD] The client SHOULD maintain a counter of such dropped data.
  - [ ] [SHOULD] The client SHOULD interpret gRPC status codes as retryable or not-retryable according to the following table.
  - [ ] [SHOULD] When retrying, the client SHOULD implement an exponential backoff strategy.
  - [ ] [SHOULD] The client SHOULD interpret RESOURCE_EXHAUSTED code as retryable only if the server signals that the recovery from resource exhaustion is possible.

### OTLP/gRPC Throttling
- [ ] [MUST] The client MUST then throttle itself to avoid overwhelming the server.
- [ ] [MUST] To signal backpressure when using gRPC transport, the server MUST return an error with code Unavailable.
- [ ] [SHOULD] If the server is unable to keep up with the pace of data it receives from the client then it SHOULD signal that fact to the client.
- [ ] [SHOULD] When the client receives this signal, it SHOULD follow the recommendations outlined in documentation for RetryInfo.
- [ ] [SHOULD] The server SHOULD choose a retry_delay value that is big enough to give the server time to recover yet is not too big to cause the client to drop data while being throttled.


## OTLP/HTTP
- [x] [MUST] All server components MUST support the following transport compression options:
  - [x] [MUST] No compression, denoted by none.
  - [x] [MUST] Gzip compression, denoted by gzip.
- [ ] [SHOULD] Implementations that use HTTP/2 transport SHOULD fallback to HTTP/1.1 transport if HTTP/2 connection cannot be established.

### Binary Protobuf Encoding
- [x] [MUST] The client and the server MUST set "Content-Type: application/x-protobuf" request and response headers when sending binary Protobuf encoded payload.

### JSON Protobuf Encoding
- [x] [MUST] The client and the server MUST set "Content-Type: application/json" request and response headers when sending JSON Protobuf encoded payload.
- [x] [MUST] Values of enum fields MUST be encoded as integer values.
- [x] [MUST] OTLP/JSON receivers MUST ignore message fields with unknown names and MUST unmarshal the message as if the unknown field was not present in the payload.

### OTLP/HTTP Request
- [x] [MUST] The client MAY gzip the content and in that case MUST include "Content-Encoding: gzip" request header.

### OTLP/HTTP Response
- [x] [MUST] The response body MUST be the appropriate serialized Protobuf message.
- [x] [MUST] The server MUST set "Content-Type: application/x-protobuf" header if the response body is binary-encoded Protobuf payload.
- [x] [MUST] The server MUST set "Content-Type: application/json" if the response is JSON-encoded Protobuf payload.
- [x] [MUST] The server MUST use the same "Content-Type" in the response as it received in the request.
- Full Success
  - [x] [MUST] On success, the server MUST respond with HTTP 200 OK
  - [x] [MUST] The response body MUST be a Protobuf-encoded Export<signal>ServiceResponse message.
  - [x] [MUST] The server MUST leave the partial_success field unset in case of a successful response.
  - [x] [SHOULD] If the server receives an empty request the server SHOULD respond with success.
- Partial Success (NOTE: Currentry, it does not support partially accepting)
  - [ ] [MUST] If the request is only partially accepted, the server MUST respond with HTTP 200 OK.
  - [ ] [MUST] The response body MUST be the same Export<signal>ServiceResponse message as in the Full Success case.
  - [ ] [MUST] The server MUST initialize the partial_success field, and it MUST set the respective rejected_spans, rejected_data_points, rejected_log_records or rejected_profiles field with the number of spans/data points/log records it rejected.
  - [ ] [MUST] Servers MAY also use the partial_success field to convey warnings/suggestions to clients even when it fully accepts the request. In such cases, the rejected_<signal> field MUST have a value of 0, and the error_message field MUST be non-empty.
  - [ ] [MUST] The client MUST NOT retry the request when it receives a partial success response where the partial_success is populated.
  - [ ] [SHOULD] The server SHOULD populate the error_message field with a human-readable error message in English.
- Failures
  - [x] [MUST] If the processing of the request fails, the server MUST respond with appropriate HTTP 4xx or HTTP 5xx status code.
  - [ ] [MUST] The response body for all HTTP 4xx and HTTP 5xx responses MUST be a Protobuf-encoded Status message that describes the problem.
  - [ ] [SHOULD] The Status.message field SHOULD contain a developer-facing error message as defined in Status message schema.
  - [ ] [SHOULD] The server SHOULD use HTTP response status codes to indicate retryable and not-retryable errors for a particular erroneous situation.
  - [x] [SHOULD] The client SHOULD honour HTTP response status codes as retryable or not-retryable.
- Retryable Response Codes
  - [x] [MUST] All other 4xx or 5xx response status codes MUST NOT be retried.
  - [x] [SHOULD] The requests that receive a response status code listed in following table SHOULD be retried.
- Bad Data
  - [x] [MUST] If the processing of the request fails because the request contains data that cannot be decoded or is otherwise invalid and such failure is permanent, then the server MUST respond with HTTP 400 Bad Request.
  - [x] [MUST] The client MUST NOT retry the request when it receives HTTP 400 Bad Request response.
  - [ ] [SHOULD] The Status.details field in the response SHOULD contain a BadRequest that describes the bad data.
- OTLP/HTTP Throttling
  - [ ] [SHOULD] If the server receives more requests than the client is allowed or the server is overloaded, the server SHOULD respond with HTTP 429 Too Many Requests or HTTP 503 Service Unavailable.
  - [ ] [SHOULD] The client SHOULD honour the waiting interval specified in the "Retry-After" header if it is present.
  - [ ] [SHOULD] The "Retry-After" header is not present in the response, then the client SHOULD implement an exponential backoff strategy between retries.
- All Other Responses
  - [x] [SHOULD] If the server disconnects without returning a response, the client SHOULD retry and send the same request.
  - [x] [SHOULD] The client SHOULD implement an exponential backoff strategy between retries to avoid overwhelming the server.

### OTLP/HTTP Connection
- [ ] [SHOULD] If the client cannot connect to the server, the client SHOULD retry the connection using an exponential backoff strategy between retries.
- [ ] [SHOULD] The client SHOULD keep the connection alive between requests.
- [ ] [SHOULD] Server implementations SHOULD accept OTLP/HTTP with binary-encoded Protobuf payload and OTLP/HTTP with JSON-encoded Protobuf payload requests on the same port and multiplex the requests to the corresponding payload decoder based on the "Content-Type" request header.

### OTLP/HTTP Concurrent Requests
- [ ] [SHOULD] To achieve higher total throughput, the client MAY send requests using several parallel HTTP connections. In that case, the maximum number of parallel connections SHOULD be configurable.

# Future Versions and Interoperability
- [ ] [MUST] When possible, the interoperability MUST be ensured between all versions of OTLP that are not declared obsolete.
