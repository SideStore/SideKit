//
//  ServerConnection.swift
//  AltStore
//
//  Created by Riley Testut on 1/7/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation

@objc(ALTServerConnection) @objcMembers
public class ServerConnection: NSObject {
    public let server: Server
    public let connection: Connection

    init(server: Server, connection: Connection) {
        self.server = server
        self.connection = connection
    }

    deinit {
        self.connection.disconnect()
    }

    public func disconnect() {
        connection.disconnect()
    }
}

public extension ServerConnection {
    func enableUnsignedCodeExecution(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let udid = Bundle.main.object(forInfoDictionaryKey: "ALTDeviceID") as? String else {
            return ServerManager.shared.callbackQueue.async {
                completion(.failure(ConnectionError.unknownUDID))
            }
        }

        enableUnsignedCodeExecution(udid: udid, completion: completion)
    }

    func enableUnsignedCodeExecution(udid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        func finish(_ result: Result<Void, Error>) {
            ServerManager.shared.callbackQueue.async {
                completion(result)
            }
        }

        let request = EnableUnsignedCodeExecutionRequest(udid: udid, processID: ProcessInfo.processInfo.processIdentifier)

        send(request) { result in
            switch result {
            case let .failure(error): finish(.failure(error))
            case .success:
                self.receiveResponse { result in
                    switch result {
                    case let .failure(error): finish(.failure(error))
                    case let .success(.error(response)): finish(.failure(response.error))
                    case .success(.enableUnsignedCodeExecution): finish(.success(()))
                    case .success: finish(.failure(ALTServerError.unknownResponse))
                    }
                }
            }
        }
    }
}

public extension ServerConnection {
    @objc(enableUnsignedCodeExecutionWithCompletionHandler:)
    func __enableUnsignedCodeExecution(completion: @escaping (Bool, Error?) -> Void) {
        enableUnsignedCodeExecution { result in
            switch result {
            case let .failure(error): completion(false, error)
            case .success: completion(true, nil)
            }
        }
    }

    @objc(enableUnsignedCodeExecutionWithUDID:completionHandler:)
    func __enableUnsignedCodeExecution(udid: String, completion: @escaping (Bool, Error?) -> Void) {
        enableUnsignedCodeExecution(udid: udid) { result in
            switch result {
            case let .failure(error): completion(false, error)
            case .success: completion(true, nil)
            }
        }
    }
}

private extension ServerConnection {
    func send<T: Encodable>(_ payload: T, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        do {
            let data: Data

            if let payload = payload as? Data {
                data = payload
            } else {
                data = try JSONEncoder().encode(payload)
            }

            func process<T>(_ result: Result<T, ALTServerError>) -> Bool {
                switch result {
                case .success: return true
                case let .failure(error):
                    completionHandler(.failure(error))
                    return false
                }
            }

            let requestSize = Int32(data.count)
            let requestSizeData = withUnsafeBytes(of: requestSize) { Data($0) }

            connection.send(requestSizeData) { result in
                guard process(result) else { return }

                self.connection.send(data) { result in
                    guard process(result) else { return }
                    completionHandler(.success(()))
                }
            }
        } catch {
            print("Invalid request.", error)
            completionHandler(.failure(ALTServerError.invalidRequest(underlyingError: error)))
        }
    }

    func receiveResponse(completionHandler: @escaping (Result<ServerResponse, Error>) -> Void) {
        let size = MemoryLayout<Int32>.size

        connection.receiveData(expectedSize: size) { result in
            do {
                let data = try result.get()

                let expectedBytes = Int(data.withUnsafeBytes { $0.load(as: Int32.self) })
                self.connection.receiveData(expectedSize: expectedBytes) { result in
                    do {
                        let data = try result.get()

                        let response = try JSONDecoder().decode(ServerResponse.self, from: data)
                        completionHandler(.success(response))
                    } catch {
                        completionHandler(.failure(ALTServerError(error)))
                    }
                }
            } catch {
                completionHandler(.failure(ALTServerError(error)))
            }
        }
    }
}
