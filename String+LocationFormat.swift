extension String {
    func formatLocation() -> String {
        if self.hasPrefix("0.0 nm from ") {
            return "in " + self.replacingOccurrences(of: "0.0 nm from ", with: "")
        }
        return self
    }
} 