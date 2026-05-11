import { StringValueObject } from "../../../shared/domain/StringValueObject";

export class ProductName extends StringValueObject {
	constructor(value: string) {
		super(value);
		this.ensureIsValidName(value);
	}

	equals(other: ProductName): boolean {
		return this.value.toLowerCase() === other.value.toLowerCase();
	}

	private ensureIsValidName(value: string): void {
		const trimmed = value.trim();
		if (trimmed.length === 0) {
			throw new Error("Product name cannot be empty");
		}
		if (trimmed.length > 255) {
			throw new Error("Product name too long");
		}
	}
}
