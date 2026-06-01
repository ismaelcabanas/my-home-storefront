import { Cursor } from "../../../../../src/contexts/inventory/inventory-items/domain/Cursor";
import { InvalidCursorError } from "../../../../../src/contexts/inventory/inventory-items/domain/InvalidCursorError";

describe("Cursor should", () => {
	it("encode and decode round-trip correctly", () => {
		// Arrange
		const originalCursor = new Cursor("Apple", new Date("2024-01-15T10:00:00.000Z"));

		// Act
		const encoded = originalCursor.encode();
		const decodedCursor = Cursor.decode(encoded);

		// Assert
		expect(decodedCursor.name).toBe(originalCursor.name);
		expect(decodedCursor.createdAt.getTime()).toBe(originalCursor.createdAt.getTime());
	});

	it("throw InvalidCursorError for invalid base64", () => {
		// Arrange
		const invalidToken = "not-valid-base64!!!";

		// Act & Assert
		expect(() => Cursor.decode(invalidToken)).toThrow(InvalidCursorError);
		expect(() => Cursor.decode(invalidToken)).toThrow("Invalid cursor format");
	});

	it("throw InvalidCursorError for invalid JSON", () => {
		// Arrange
		const invalidJson = Buffer.from("not-json").toString("base64");

		// Act & Assert
		expect(() => Cursor.decode(invalidJson)).toThrow(InvalidCursorError);
	});

	it("throw InvalidCursorError for missing fields", () => {
		// Arrange
		const incompletePrimitives = { name: "Apple" };
		const json = JSON.stringify(incompletePrimitives);
		const encodedToken = Buffer.from(json).toString("base64");

		// Act & Assert
		expect(() => Cursor.decode(encodedToken)).toThrow();
	});

	it("throw error for invalid date in fromPrimitives", () => {
		// Arrange
		const invalidPrimitives = {
			name: "Apple",
			createdAt: "not-a-date",
		};

		// Act & Assert
		expect(() => Cursor.fromPrimitives(invalidPrimitives)).toThrow("Cursor createdAt must be a valid ISO 8601 date");
	});

	it("throw error for empty name in fromPrimitives", () => {
		// Arrange
		const invalidPrimitives = {
			name: "",
			createdAt: "2024-01-15T10:00:00.000Z",
		};

		// Act & Assert
		expect(() => Cursor.fromPrimitives(invalidPrimitives)).toThrow("Cursor name cannot be empty");
	});
});
