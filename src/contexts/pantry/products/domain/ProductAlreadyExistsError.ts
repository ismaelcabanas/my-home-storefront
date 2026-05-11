import { ApplicationError } from "../../../shared/domain/ApplicationError";

export class ProductAlreadyExistsError extends ApplicationError {
	constructor(productName: string) {
		super({ productName });
	}

	override get message(): string {
		return "PRODUCT_ALREADY_EXISTS";
	}
}
