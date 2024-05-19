// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Swoir
import Swoirenberg

let SERVER_URL = "https://ocelots-beta-server-f8ada60e3d7d.herokuapp.com"

struct ProofRequest: Codable {
    let id: String
    let min_age: Int?
    let current_date: String?
    let status: String
    let citizenship: String?
    let proof: String?
}

func bytes_to_data(_ bytes: [UInt8]) -> Data {
    return Data(bytes)
}

func data_to_bytes(_ data: Data) -> [UInt8] {
    return [UInt8](data)
}

func data_to_hex(_ data: Data) -> String {
    return data.map { String(format: "%02x", $0) }.joined()
}

func utf8_to_data(_ utf8: String) -> Data {
    return Data(utf8.utf8)
}

// Function to perform the async HTTP POST request
func asyncHttpPost(urlString: String, postData: [String: Any]) async throws -> ProofRequest {
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL)
    }

    // Convert the dictionary to JSON data
    let jsonData = try JSONSerialization.data(withJSONObject: postData, options: [])

    // Create the URLRequest object
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData

    // Use URLSession to perform the request
    let (data, response) = try await URLSession.shared.data(for: request)

    // Check the response status
    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
        throw URLError(.badServerResponse)
    }

    let proofRequest = try JSONDecoder().decode(ProofRequest.self, from: data)

    return proofRequest
}

func createProofRequest() async -> ProofRequest? {
    let postData: [String: Any] = ["min_age": 18, "current_date": "20240519"]

    do {
        let urlString = "\(SERVER_URL)/request/create"
        let proofRequest = try await asyncHttpPost(urlString: urlString, postData: postData)
        return proofRequest
    } catch {
        print("Error: \(error)")
    }
    return nil
}

func markProofRequestAsPending(requestId: String) async -> ProofRequest? {
    let postData: [String: Any] = ["requestId": requestId]

    do {
        let urlString = "\(SERVER_URL)/request/start"
        let proofRequest = try await asyncHttpPost(urlString: urlString, postData: postData)
        return proofRequest
    } catch {
        print("Error: \(error)")
    }
    return nil
}

func markProofRequestAsAccepted(requestId: String) async -> ProofRequest? {
    let postData: [String: Any] = ["requestId": requestId]

    do {
        let urlString = "\(SERVER_URL)/request/accept"
        let proofRequest = try await asyncHttpPost(urlString: urlString, postData: postData)
        return proofRequest
    } catch {
        print("Error: \(error)")
    }
    return nil

}

func completeProofRequest(requestId: String, proof: String) async -> ProofRequest? {
    let postData: [String: Any] = ["requestId": requestId, "proof": proof]

    do {
        let urlString = "\(SERVER_URL)/request/complete"
        let proofRequest = try await asyncHttpPost(urlString: urlString, postData: postData)
        return proofRequest
    } catch {
        print("Error: \(error)")
    }
    return nil
}

func newRequest() async throws {

    let swoir = Swoir(backend: Swoirenberg.self)
    let manifest = URL(fileURLWithPath: "./proof_age.json")
    let circuit = try swoir.createCircuit(manifest: manifest)

    var proofRequest = await createProofRequest()
    if proofRequest == nil {
        print("Failed to create proof request")
        return
    }

    proofRequest = await markProofRequestAsPending(requestId: proofRequest!.id)
    if proofRequest == nil {
        print("Failed to mark proof request as pending")
        return
    }
    proofRequest = await markProofRequestAsAccepted(requestId: proofRequest!.id)

    let mrz = bytes_to_data([80, 60, 85, 84, 79, 83, 77, 73, 84, 72, 60, 60, 74, 79, 72, 78, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 49, 50, 51, 52, 53, 54, 55, 56, 57, 49, 85, 84, 79, 56, 53, 48, 51, 50, 51, 56, 77, 50, 56, 48, 50, 49, 53, 52, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 48, 48])
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    dateFormatter.locale = Locale.current

    let formattedDate = dateFormatter.string(from: Date())
    let current_date = utf8_to_data(formattedDate)
    let min_age_required = 18
    print([ "mrz": mrz, "current_date": current_date, "min_age_required": min_age_required])
    let proof = try circuit.prove([ "mrz": mrz, "current_date": current_date, "min_age_required": min_age_required])

    let proofHex = String(data_to_hex(proof.proof).suffix(4288))

    proofRequest = await completeProofRequest(requestId: proofRequest!.id, proof: proofHex)
    if proofRequest == nil {
        print("Failed to send proof")
        return
    }
    print(proofRequest!)

    let verified = try circuit.verify(proof)
    print(verified ? "Verified!" : "Failed to verify")
}

func continueRequest(requestId: String) async throws {

    let swoir = Swoir(backend: Swoirenberg.self)
    let manifest = URL(fileURLWithPath: "./proof_age.json")
    let circuit = try swoir.createCircuit(manifest: manifest)

    var proofRequest = await markProofRequestAsPending(requestId: requestId)
    if proofRequest == nil {
        print("Failed to mark proof request as pending")
        return
    }
    proofRequest = await markProofRequestAsAccepted(requestId: proofRequest!.id)

    let mrz = bytes_to_data([80, 60, 85, 84, 79, 83, 77, 73, 84, 72, 60, 60, 74, 79, 72, 78, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 49, 50, 51, 52, 53, 54, 55, 56, 57, 49, 85, 84, 79, 56, 53, 48, 51, 50, 51, 56, 77, 50, 56, 48, 50, 49, 53, 52, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 48, 48])
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    dateFormatter.locale = Locale.current

    let formattedDate = dateFormatter.string(from: Date())

    let current_date = utf8_to_data(formattedDate)
    let min_age_required = 18
    let proof = try circuit.prove([ "mrz": mrz, "current_date": current_date, "min_age_required": min_age_required])

    let length = 2144
    let startIndex = max(0, proof.proof.count - length)
    let proofOnly = proof.proof.subdata(in: startIndex..<proof.proof.count)

    proofRequest = await completeProofRequest(requestId: proofRequest!.id, proof: data_to_hex(proofOnly))
    if proofRequest == nil {
        print("Failed to send proof")
        return
    }
    print(proofRequest!)

    let verified = try circuit.verify(proof)
    print(verified ? "Verified!" : "Failed to verify")
}

try await newRequest()
try await continueRequest(requestId: "1aee37e6-ab0c-405d-bbbf-33c45aedbe6a")
