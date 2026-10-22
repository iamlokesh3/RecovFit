import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let text: String
    let isUser: Bool
    var time: Date = Date()
}

// MARK: - Main Chat View
struct ChatBotView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading = false
    @Namespace private var bottomID

    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [.purple.opacity(0.2), .blue.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "stethoscope.circle.fill")
                        .resizable()
                        .frame(width: 38, height: 38)
                        .foregroundColor(.purple)
                    Text("AI Health Assistant")
                        .font(.title2.bold())
                        .foregroundStyle(.linearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)

                // Chat ScrollView
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(messages) { message in
                                chatBubble(for: message)
                                    .transition(.scale.combined(with: .opacity))
                                    .id(message.id)
                            }

                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Spacer()
                                }
                                .padding(.top, 4)
                            }

                            Color.clear.frame(height: 1).id(bottomID)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .onChange(of: messages.count) { _, _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                proxy.scrollTo(bottomID, anchor: .bottom)
                            }
                        }
                    }
                }

                // Input Area
                HStack(spacing: 12) {
                    TextField("Type your message...", text: $inputText)
                        .padding(14)
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)

                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.white)
                            .padding(14)
                            .background(
                                LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .clipShape(Circle())
                            )
                            .shadow(color: .purple.opacity(0.3), radius: 5, y: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
                .shadow(color: .black.opacity(0.1), radius: 6, y: -3)
                .padding(.horizontal)
            }
        }
        .onAppear {
            if messages.isEmpty {
                messages.append(ChatMessage(text: "👋 Hello! How are you feeling today?", isUser: false))
            }
        }
    }

    // MARK: - Chat Bubble
    @ViewBuilder
    func chatBubble(for message: ChatMessage) -> some View {
        HStack(alignment: .bottom) {
            if !message.isUser {
                Image(systemName: "person.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.blue.opacity(0.7))
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(16)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    message.isUser
                                    ? AnyShapeStyle(LinearGradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(Color.white.opacity(0.3))
                                )
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(message.isUser ? Color.white.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                        }
                    )

                    .foregroundColor(message.isUser ? .white : .primary)
                    .font(.body)
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.isUser ? .trailing : .leading)
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)

                Text(message.time, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            if message.isUser {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundColor(.purple.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: message.isUser ? .trailing : .leading)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: messages.count)
    }

    // MARK: - Message Logic
    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(ChatMessage(text: trimmed, isUser: true))
        inputText = ""
        isLoading = true

        if isTamil(trimmed) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isLoading = false
                self.messages.append(ChatMessage(text: "தயவுசெய்து உங்கள் ஆரோக்கியம் பற்றி கேளுங்கள். உதாரணம்: 'எனக்கு முதுகு வலி'", isUser: false))
            }
        } else {
            OpenRouterService.shared.sendMessage(prompt: trimmed) { response in
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.messages.append(ChatMessage(text: response, isUser: false))
                }
            }
        }
    }

    // MARK: - Tamil Detection
    private func isTamil(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if scalar.value >= 0x0B80 && scalar.value <= 0x0BFF { return true }
        }
        return false
    }
}

// MARK: - API Handler
class OpenRouterService {
    static let shared = OpenRouterService()
    private var apiToken: String {
        if let token = ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"], !token.isEmpty {
            return token
        }
        return "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"
    }
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"

    func sendMessage(prompt: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion("Invalid API URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("openai", forHTTPHeaderField: "HTTP-Referer")

        let body: [String: Any] = [
            "model": "openrouter/auto",
            "messages": [
                ["role": "system", "content": "You are a helpful health assistant."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 512,
            "temperature": 0.7
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion("Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                completion("No data received.")
                return
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                completion(content.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                let raw = String(data: data, encoding: .utf8) ?? "Unreadable response"
                print("⚠️ API Raw Response: \(raw)")
                completion("No valid response.")
            }
        }.resume()
    }
}
