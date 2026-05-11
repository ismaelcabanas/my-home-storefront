import { ApplicationError } from "../../../shared/domain/ApplicationError";

export class InvalidStockLevelError extends ApplicationError {
	constructor(reason: string) {
		super({ reason });
	}

	override get message(): string {
		return "INVALID_STOCK_LEVEL";
	}
}
