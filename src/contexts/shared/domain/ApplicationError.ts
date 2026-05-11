type ApplicationErrorPrimitives = {
	type: string;
	params: Record<string, unknown>;
};

export abstract class ApplicationError extends Error {
	constructor(public readonly params: Record<string, unknown> = {}) {
		super();
	}

	abstract override get message(): string;

	toPrimitives(): ApplicationErrorPrimitives {
		return {
			type: this.message,
			params: this.params,
		};
	}
}
