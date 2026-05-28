import { StringValueObject } from "../../../shared/domain/StringValueObject";

import { InvalidInventoryItemNameError } from "./InvalidInventoryItemNameError";

export class InventoryItemName extends StringValueObject {
	private static readonly MAX_LENGTH = 255;

	private constructor(value: string) {
		super(value);
	}

	static create(value: string): InventoryItemName {
		const trimmed = value.trim();

		if (trimmed.length === 0) {
			throw new InvalidInventoryItemNameError(value);
		}

		if (trimmed.length > InventoryItemName.MAX_LENGTH) {
			throw new InvalidInventoryItemNameError(value);
		}

		return new InventoryItemName(trimmed);
	}
}
