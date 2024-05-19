// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Swoir
import Swoirenberg

let SERVER_URL = "https://ocelots-beta-server-f8ada60e3d7d.herokuapp.com"

let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyyMMdd"
dateFormatter.locale = Locale.current

let formattedDate = dateFormatter.string(from: Date())
let current_date = utf8_to_data(formattedDate)

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
    let postData: [String: Any] = ["min_age": 18, "current_date": formattedDate]

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

/**
* Simulate the whole userflow that would happen between the mobile app and the website
**/
func newRequest() async throws {

    // Loads Swoir with the Swoirenberg backend
    let swoir = Swoir(backend: Swoirenberg.self)
    // Loads the manifest file
    let manifest = URL(fileURLWithPath: "./proof_age.json")
    // Creates a circuit from the manifest
    let circuit = try swoir.createCircuit(manifest: manifest)

    // Create a proof request - this would be done by the website
    // It responds with a newly created proof request that contains
    // a randomly generated id and the conditions to be met for the proof 
    var proofRequest = await createProofRequest()
    if proofRequest == nil {
        print("Failed to create proof request")
        return
    }

    // Mark the proof request as pending - this would be done by the mobile app
    // when the user scan the QR code and the app has subsequently received the request id
    // It responds with the proof request that has been marked as pending
    proofRequest = await markProofRequestAsPending(requestId: proofRequest!.id)
    if proofRequest == nil {
        print("Failed to mark proof request as pending")
        return
    }

    // Mark the proof request as accepted - this would be done by the mobile app
    // when the user clicks on Accept or Approve
    // It responds with the proof request that has been marked as accepted
    proofRequest = await markProofRequestAsAccepted(requestId: proofRequest!.id)

    let mrz = bytes_to_data([80, 60, 85, 84, 79, 83, 77, 73, 84, 72, 60, 60, 74, 79, 72, 78, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 49, 50, 51, 52, 53, 54, 55, 56, 57, 49, 85, 84, 79, 56, 53, 48, 51, 50, 51, 56, 77, 50, 56, 48, 50, 49, 53, 52, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 60, 48, 48])

    let min_age_required = 18
    print([ "mrz": mrz, "current_date": current_date, "min_age_required": min_age_required])
    // Generate the proof using Swoir - this would be done by the mobile app
    let proof = try circuit.prove([ "mrz": mrz, "current_date": current_date, "min_age_required": min_age_required])

    let proofHex = String(data_to_hex(proof.proof).suffix(4288))

    // Complete the proof request - this would be done by the mobile app
    // when the proof has been generated and is ready to be sent
    // It responds with the proof request that has been marked as completed
    // and now contains the proof and a status indicating if the proof was successfully
    // verified or not on the server
    proofRequest = await completeProofRequest(requestId: proofRequest!.id, proof: proofHex)
    if proofRequest == nil {
        print("Failed to send proof")
        return
    }
    print(proofRequest!)

    let verified = try circuit.verify(proof)
    print(verified ? "Verified!" : "Failed to verify")
}

try await newRequest()
