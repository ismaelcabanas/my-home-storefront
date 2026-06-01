import { CodelyError } from "../../../shared/domain/CodelyError";

export class InvalidCursorError extends CodelyError {
	constructor(
		private readonly errorMessage: string,
		public readonly cursor: string,
	) {
		super({ cursor });
	}

	override get message(): string {
		return this.errorMessage;
	}
}
