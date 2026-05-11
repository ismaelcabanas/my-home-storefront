import { faker } from "@faker-js/faker";

import { ProductStock } from "../../../../../src/contexts/pantry/products/domain/ProductStock";

export class ProductStockMother {
	static create(value?: number): ProductStock {
		return new ProductStock(
			value ?? faker.number.int({ min: 0, max: 100 }),
		);
	}

	static zero(): ProductStock {
		return new ProductStock(0);
	}

	static withValue(value: number): ProductStock {
		return new ProductStock(value);
	}
}
