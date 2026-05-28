import { CodelyError } from "../../../shared/domain/CodelyError";

export class InvalidInventoryItemNameError extends CodelyError {
	constructor(name: string) {
		super({ name });
	}

	override get message(): string {
		return "InvalidInventoryItemName";
	}
}
