import { CodelyError } from "../../../shared/domain/CodelyError";

export class InventoryItemNotFoundError extends CodelyError {
	constructor(itemId: string) {
		super({ itemId });
	}

	override get message(): string {
		return "InventoryItemNotFound";
	}
}
