import { StringValueObject } from "../../../shared/domain/StringValueObject";

export class InventoryItemState extends StringValueObject {
	private static readonly AVAILABLE = "Available";
	private static readonly LOW = "Low";
	private static readonly DEPLETED = "Depleted";
	private static readonly VALID_STATES = [
		InventoryItemState.AVAILABLE,
		InventoryItemState.LOW,
		InventoryItemState.DEPLETED,
	];

	private constructor(value: string) {
		super(value);
	}

	static Available(): InventoryItemState {
		return new InventoryItemState(InventoryItemState.AVAILABLE);
	}

	static Low(): InventoryItemState {
		return new InventoryItemState(InventoryItemState.LOW);
	}

	static Depleted(): InventoryItemState {
		return new InventoryItemState(InventoryItemState.DEPLETED);
	}

	static fromValue(value: string): InventoryItemState {
		if (!InventoryItemState.VALID_STATES.includes(value)) {
			throw new Error(`Invalid inventory item state: ${value}`);
		}

		return new InventoryItemState(value);
	}

	isAvailable(): boolean {
		return this.value === InventoryItemState.AVAILABLE;
	}

	derivesRequiresPurchase(): boolean {
		return !this.isAvailable();
	}
}
