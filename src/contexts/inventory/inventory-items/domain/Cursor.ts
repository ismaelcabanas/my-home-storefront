import { InvalidCursorError } from "./InvalidCursorError";

export interface CursorPrimitives {
	name: string;
	createdAt: string;
}

export class Cursor {
	constructor(
		public readonly name: string,
		public readonly createdAt: Date,
	) {}

	/**
	 * Decodes a base64 token to reconstruct a Cursor
	 * @param token - Base64-encoded cursor token
	 * @returns Cursor instance
	 * @throws InvalidCursorError if token is malformed or invalid
	 */
	static decode(token: string): Cursor {
		try {
			const json = Buffer.from(token, "base64").toString("utf-8");
			const primitives = JSON.parse(json) as CursorPrimitives;

			return Cursor.fromPrimitives(primitives);
		} catch (_error) {
			throw new InvalidCursorError("Invalid cursor format", token);
		}
	}

	/**
	 * Creates a Cursor from primitive values
	 * @param primitives - Object containing name and createdAt
	 * @returns Cursor instance
	 * @throws Error if name is empty or createdAt is invalid
	 */
	static fromPrimitives(primitives: CursorPrimitives): Cursor {
		if (!primitives.name || primitives.name.trim() === "") {
			throw new Error("Cursor name cannot be empty");
		}

		const createdAt = new Date(primitives.createdAt);
		if (isNaN(createdAt.getTime())) {
			throw new Error("Cursor createdAt must be a valid ISO 8601 date");
		}

		return new Cursor(primitives.name, createdAt);
	}

	/**
	 * Encodes the cursor to a base64 string for use in pagination tokens
	 * @returns Base64-encoded JSON string containing name and createdAt
	 */
	encode(): string {
		const primitives = {
			name: this.name,
			createdAt: this.createdAt.toISOString(),
		};
		const json = JSON.stringify(primitives);

		return Buffer.from(json).toString("base64");
	}
}
