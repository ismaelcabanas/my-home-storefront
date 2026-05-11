import { NumberValueObject } from "../../../shared/domain/NumberValueObject";

import { InvalidStockLevelError } from "./InvalidStockLevelError";

export class ProductStock extends NumberValueObject {
	constructor(value: number) {
		super(value);
		this.ensureIsValidStock(value);
	}

	private ensureIsValidStock(value: number): void {
		if (!Number.isInteger(value)) {
			throw new InvalidStockLevelError("Stock must be an integer");
		}
		if (value < 0) {
			throw new InvalidStockLevelError("Stock cannot be negative");
		}
	}
}
