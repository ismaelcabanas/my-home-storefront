import { faker } from "@faker-js/faker";

import { ProductName } from "../../../../../src/contexts/pantry/products/domain/ProductName";

export class ProductNameMother {
	static create(value?: string): ProductName {
		return new ProductName(value ?? faker.commerce.productName());
	}

	static withName(name: string): ProductName {
		return new ProductName(name);
	}
}
